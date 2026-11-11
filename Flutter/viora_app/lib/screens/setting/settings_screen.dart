import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../providers/theme_provider.dart';
import '../../services/session_service.dart';
import '../../widgets/bottomsheet/app_change_account.dart';
import '../../widgets/app_switch.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.setting,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _buildSectionHeader(context, l10n.themeAndDisplay),
              const SizedBox(height: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderTheme),
                  boxShadow: [
                    BoxShadow(
                      color: context.settingsCardBg,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      l10n.darkMode,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      l10n.darkModeSub,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textMuted,
                      ),
                    ),
                    trailing: AppSwitch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme(value);
                      },
                    ),
                    onTap: () {
                      themeProvider.toggleTheme(!themeProvider.isDarkMode);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionHeader(context, l10n.activity),
              const SizedBox(height: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderTheme),
                  boxShadow: [
                    BoxShadow(
                      color: context.settingsCardBg,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.bar_chart_rounded,
                      title: l10n.activity,
                      subtitle: l10n.todayScreenTime,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.activity),
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.history_rounded,
                      title: l10n.watchHistory,
                      subtitle: l10n.watchHistorySub,
                      onTap: () {},
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.favorite_border_rounded,
                      title: l10n.likeHistory,
                      subtitle: l10n.likeHistorySub,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.likeHistory),
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.commentHistory,
                      subtitle: l10n.commentHistorySub,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.commentHistory),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionHeader(context, l10n.general),
              const SizedBox(height: 10),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderTheme),
                  boxShadow: [
                    BoxShadow(
                      color: context.settingsCardBg,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.notifications_none_rounded,
                      title: l10n.notifications,
                      subtitle: l10n.notificationsSub,
                      onTap: () {},
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.security_outlined,
                      title: l10n.privacyAndSecurity,
                      subtitle: l10n.privacySecuritySub,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.privacySecurity),
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.description_outlined,
                      title: l10n.termsOfService,
                      subtitle: l10n.termsSub,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.termsOfService),
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.lock_outline_rounded,
                      title: l10n.privacyPolicy,
                      subtitle: l10n.privacyPolicySub,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicy),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionHeader(context, l10n.account),
              const SizedBox(height: 10),

              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.borderTheme),
                  boxShadow: [
                    BoxShadow(
                      color: context.settingsCardBg,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      context,
                      icon: Icons.swap_horiz_rounded,
                      title: l10n.changeAccount,
                      subtitle: l10n.notificationsSub,
                      onTap: () => AppChangeAccountBottomSheet.show(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => _showSignOutDialog(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  label: Text(
                    l10n.signOut,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.blue, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: context.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: context.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.textSubtle,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5, 
      indent: 64,
      endIndent: 16,
      color: context.borderTheme,
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
              style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
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
              style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
