import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../providers/theme_provider.dart';
import '../../services/call_service.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../services/social_notification_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/language_switcher.dart';
import '../home/home_screen.dart';
import '../message/messages_screen.dart';
import '../contact/contact_screen.dart';
import '../notification/notification_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String email;
  const MainScreen({super.key, required this.email});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  late List<Widget> _pages;
  String? _userAvatar;
  String? _userName;
  bool _hasUnreadNotifications = false;
  late final Function(Map<String, dynamic>) _onNewNotification;

  void _openDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  void initState() {
    super.initState();
    SocketService.init();
    CallService.initialize();
    _initPages();
    _loadUserProfile();
    _initNotificationBadge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallService.isAppReadyForNavigation = true;
      CallService.consumePendingAcceptedCall();
    });
  }

  void _initNotificationBadge() {
    _checkUnreadNotifications();
    _onNewNotification = (data) {
      if (!mounted) return;
      final type = data['type']?.toString();
      if (type == 'message') return;
      if (_selectedIndex != 3) {
        setState(() {
          _hasUnreadNotifications = true;
        });
      }
    };
    SocketService.onNewNotification(_onNewNotification);
  }

  Future<void> _checkUnreadNotifications() async {
    final res = await SocialNotificationService.fetchNotifications();
    if (mounted && res != null && (res['unreadCount'] ?? 0) > 0) {
      setState(() {
        _hasUnreadNotifications = true;
      });
    }
  }

  @override
  void dispose() {
    CallService.isAppReadyForNavigation = false;
    SocketService.offNewNotification(_onNewNotification);
    super.dispose();
  }

  void _initPages() {
    _pages = [
      HomeScreen(
        email: widget.email,
        userAvatar: _userAvatar,
        userName: _userName,
        onMenuPressed: _openDrawer,
      ),
      MessagesScreen(
        onMenuPressed: _openDrawer,
      ),
      const ContactScreen(),
      const NotificationScreen(),
      ProfileScreen(email: widget.email),
    ];
  }

  Future<void> _loadUserProfile() async {
    final cachedAvatar = await SessionService.getAvatar();
    final cachedUsername = await SessionService.getUsername();
    if (mounted && (cachedAvatar != null || cachedUsername != null)) {
      setState(() {
        _userAvatar = cachedAvatar;
        _userName = cachedUsername;
        _initPages();
      });
    }

    final profile = await ProfileService.getProfile(email: widget.email);
    if (profile != null && mounted) {
      setState(() {
        _userAvatar = profile['avatar']?.toString() ?? _userAvatar;
        _userName = profile['username']?.toString() ?? _userName;
        _initPages();
      });
    } else {

      final isValid = await SessionService.validateSessionWithServer();
      if (!isValid && mounted) {
        _showAccountDeletedDialog();
      }
    }
  }

  bool _isShowingDeletedDialog = false;

  void _showAccountDeletedDialog() {
    if (_isShowingDeletedDialog) return;
    _isShowingDeletedDialog = true;

    final l10n = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.accountDeletedTitle,
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          l10n.accountDeletedMessage,
          style: TextStyle(color: context.textMuted, fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.agree, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? context.textPrimary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor ?? context.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.textSubtle,
          size: 18,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = Language.of(context);

    final navItems = [
      NavItemData(inactiveIcon: Icons.home_outlined, activeIcon: Icons.home, label: l10n.home),
      NavItemData(inactiveIcon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: l10n.messages),
      NavItemData(inactiveIcon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: l10n.contacts),
      NavItemData(
        inactiveIcon: Icons.notifications_outlined,
        activeIcon: Icons.notifications_rounded,
        label: l10n.notificationsNav,
        hasBadge: _hasUnreadNotifications,
      ),
      NavItemData(inactiveIcon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: l10n.profile),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      endDrawer: Drawer(
        backgroundColor: context.cardBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            bottomLeft: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedIndex = 4;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 28.0, left: 20.0, right: 20.0, bottom: 28.0),
                  child: Row(
                    children: [
                      AppAvatar(
                        avatar: _userAvatar,
                        name: _userName ?? widget.email,
                        radius: 28,
                        fontSize: 20,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedIndex = 4;
                          });
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _userName != null && _userName!.isNotEmpty
                                  ? _userName!
                                  : widget.email.split('@')[0],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: context.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.textSubtle,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 0.5, indent: 20, endIndent: 20),
              const SizedBox(height: 16),

              _buildDrawerItem(
                context,
                icon: Icons.person_outline_rounded,
                title: l10n.profile,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedIndex = 4;
                  });
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.notifications_outlined,
                title: l10n.notification,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedIndex = 3;
                    _hasUnreadNotifications = false;
                  });
                },
              ),
              _buildDrawerItem(
                context,
                icon: Icons.settings_outlined,
                title: l10n.setting,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.settings);
                },
              ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.settingCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderTheme),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(
                    Provider.of<ThemeProvider>(context).isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.blue,
                    size: 22,
                  ),
                  title: Text(
                    l10n.darkMode,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: AppSwitch(
                    value: Provider.of<ThemeProvider>(context).isDarkMode,
                    onChanged: (value) {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
                    },
                  ),
                  onTap: () {
                    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
                    themeProvider.toggleTheme(!themeProvider.isDarkMode);
                  },
                ),
              ),

              const SizedBox(height: 16),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: context.settingCardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderTheme),
                ),
                child: ListTile(
                  leading: const Icon(
                    Icons.language_rounded,
                    color: AppColors.blue,
                    size: 22,
                  ),
                  title: Text(
                    l10n.language,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  trailing: const LanguageSwitcher(
                    width: 104,
                    height: 36,
                  ),
                ),
              ),

              const Spacer(),
              const Divider(height: 1, thickness: 0.5),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _scaffoldKey.currentState?.closeEndDrawer();
                      _showSignOutDialog(context);
                    },
                    icon: const Icon(Icons.logout_rounded, color: AppColors.white, size: 18),
                    label: Text(
                      l10n.signOut,
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_selectedIndex),
              child: _pages[_selectedIndex],
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                height: 70.h,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(35.r),
                  boxShadow: [
                    BoxShadow(
                      color: context.navBarShadow,
                      blurRadius: 20.r,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: context.navBarBorder,
                    width: 1,
                  ),
                ),
                child: SlidingBottomNavBar(
                  selectedIndex: _selectedIndex,
                  items: navItems,
                  onTabSelected: (newIndex) {
                    if (_selectedIndex != newIndex) {
                      setState(() {
                        _selectedIndex = newIndex;
                        if (newIndex == 3) {
                          _hasUnreadNotifications = false;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.signOut,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.signOutConfirm,
          style: TextStyle(color: context.textMuted),
        ),
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.cancel,
              style: TextStyle(
                color: context.textMuted, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SessionService.clearSession();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.welcome,
                  (route) => false,
                );
              }
            },
            child: Text(
              l10n.signOut,
              style: const TextStyle(
                color: AppColors.red, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavItemData {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool hasBadge;

  const NavItemData({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    this.hasBadge = false,
  });
}

class SlidingBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final List<NavItemData> items;

  const SlidingBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isActive = selectedIndex == index;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (selectedIndex != index) {
              onTabSelected(index);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
            child: _buildNavItem(context, index, item, isActive),
          ),
        );
      }),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, NavItemData item, bool isActive) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: isActive ? 14.w : 10.w,
        vertical: 10.h,
      ),
      decoration: BoxDecoration(
        color: isActive ? AppColors.blue : Colors.transparent,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isActive ? item.activeIcon : item.inactiveIcon,
                color: isActive ? AppColors.white : AppColors.gray,
                size: 24.r,
              ),
              if (item.hasBadge && !isActive)
                Positioned(
                  top: -2.h,
                  right: -2.w,
                  child: Container(
                    width: 8.r,
                    height: 8.r,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: Container(
                constraints: isActive 
                    ? BoxConstraints(maxWidth: 100.w) 
                    : const BoxConstraints(maxWidth: 0),
                child: isActive
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 8.w),
                          Text(
                            item.label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

