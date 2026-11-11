import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/profile_service.dart';
import '../../services/session_service.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/toast/app_toast.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _activeStatus = true;
  bool _isUpdatingActiveStatus = false;
  bool _twoFactorAuth = false;
  bool _isUpdatingTwoFactor = false;
  bool _isPrivate = false;
  bool _isUpdatingPrivate = false;
  String _whoCanMessage = 'everyone';

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final profile = await ProfileService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _isPrivate = profile['isPrivate'] == true;
          _twoFactorAuth = profile['twoFactorEnabled'] == true;
          final priv = profile['privacy'];
          if (priv is Map) {
            _whoCanMessage = priv['whoCanMessage']?.toString() ?? 'everyone';
            if (priv.containsKey('showActiveStatus')) {
              _activeStatus = priv['showActiveStatus'] != false;
            }
          }
          if (profile.containsKey('showActiveStatus')) {
            _activeStatus = profile['showActiveStatus'] != false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
    }
  }

  Future<void> _toggleActiveStatus(bool targetVal) async {
    if (_isUpdatingActiveStatus) return;
    final l10n = context.l10n;
    final prevVal = _activeStatus;

    setState(() {
      _isUpdatingActiveStatus = true;
      _activeStatus = targetVal;
    });

    final res = await ProfileService.updateActiveStatus(targetVal);
    if (!mounted) return;

    setState(() {
      _isUpdatingActiveStatus = false;
      _activeStatus = res ?? prevVal;
    });

    if (res != null) {
      AppToast.show(
        context,
        res ? l10n.activeStatusEnabledToast : l10n.activeStatusDisabledToast,
      );
    } else {
      AppToast.show(
        context,
        l10n.failedUpdatePrivacy,
        isError: true,
      );
    }
  }

  Future<void> _toggleTwoFactor(bool targetVal) async {
    if (_isUpdatingTwoFactor) return;
    final l10n = context.l10n;
    final prevVal = _twoFactorAuth;

    setState(() {
      _isUpdatingTwoFactor = true;
      _twoFactorAuth = targetVal;
    });

    final res = await ProfileService.toggleTwoFactor(targetVal);
    if (!mounted) return;

    setState(() {
      _isUpdatingTwoFactor = false;
      _twoFactorAuth = res ?? prevVal;
    });

    if (res != null) {
      AppToast.show(
        context,
        res ? l10n.twoFactorEnabledToast : l10n.twoFactorDisabledToast,
      );
    } else {
      AppToast.show(
        context,
        l10n.failedUpdateTwoFactor,
        isError: true,
      );
    }
  }

  void _confirmTogglePrivate(bool targetVal) {
    if (_isUpdatingPrivate) return;
    final l10n = context.l10n;

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: dlgCtx.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              targetVal ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
              color: AppColors.blue,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                targetVal
                    ? l10n.switchToPrivateTitle
                    : l10n.switchToPublicTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: dlgCtx.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          targetVal
              ? l10n.privateAccountDetailDesc
              : l10n.publicAccountDetailDesc,
          style: TextStyle(fontSize: 13.5, color: dlgCtx.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(l10n.cancel, style: TextStyle(color: dlgCtx.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              setState(() => _isUpdatingPrivate = true);

              final res = await ProfileService.togglePrivateAccount(targetVal);
              if (mounted) {
                setState(() {
                  _isUpdatingPrivate = false;
                  if (res != null) {
                    _isPrivate = res;
                  }
                });
                if (res != null) {
                  AppToast.show(
                    context,
                    res
                        ? l10n.privateEnabledToast
                        : l10n.publicEnabledToast,
                  );
                } else {
                  AppToast.show(
                    context,
                    l10n.failedUpdatePrivacy,
                    isError: true,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              targetVal ? l10n.agree : l10n.makePublic,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showWhoCanMessageSheet() {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetCtx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: sheetCtx.isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetCtx.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.whoCanMessage,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: sheetCtx.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildWhoCanMessageOption(
                sheetCtx,
                value: 'everyone',
                title: l10n.everyone,
                subtitle: l10n.whoCanMessageEveryoneDesc,
              ),
              Divider(height: 1, color: sheetCtx.dividerTheme),
              _buildWhoCanMessageOption(
                sheetCtx,
                value: 'friends',
                title: l10n.friends,
                subtitle: l10n.whoCanMessageFriendsDesc,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhoCanMessageOption(
    BuildContext sheetCtx, {
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _whoCanMessage == value;
    return InkWell(
      onTap: () async {
        Navigator.pop(sheetCtx);
        if (_whoCanMessage == value) return;

        setState(() => _whoCanMessage = value);
        final success = await ProfileService.updateWhoCanMessage(value);
        if (!success && mounted) {
          setState(() => _whoCanMessage = value == 'everyone' ? 'friends' : 'everyone');
          AppToast.error(context, context.l10n.failedUpdatePrivacy);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.blue : sheetCtx.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: sheetCtx.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.blue, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteAccountTap() async {
    final email = await SessionService.getUserEmail() ?? '';
    final token = await SessionService.getToken();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await http.post(
        Uri.parse(ApiConfig.getDeletionStatus),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['deletionRequested'] == true) {
          Navigator.pushNamed(context, AppRoutes.deleteAccount);
          return;
        }
      }

      http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'purpose': 'delete_account',
        }),
      );

      Navigator.pushNamed(
        context,
        AppRoutes.verifyEmail,
        arguments: {
          'email': email,
          'isDeleteAccount': true,
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.show(context, l10n.serverConnectionError, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.privacyAndSecurity,
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

              _buildSectionHeader(context, l10n.sectionPrivacy),
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
                    _buildSwitchTile(
                      context,
                      icon: Icons.lock_rounded,
                      iconColor: AppColors.blue,
                      title: l10n.privateAccount,
                      subtitle: l10n.privateAccountSubShort,
                      value: _isPrivate,
                      onChanged: _confirmTogglePrivate,
                    ),
                    _buildDivider(context),
                    _buildSwitchTile(
                      context,
                      icon: Icons.circle,
                      iconColor: Colors.green,
                      title: l10n.activeStatus,
                      subtitle: l10n.activeStatusSub,
                      value: _activeStatus,
                      onChanged: _toggleActiveStatus,
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.chat_bubble_outline_rounded,
                      title: l10n.whoCanMessage,
                      subtitle: _whoCanMessage == 'friends' ? l10n.friends : l10n.everyone,
                      onTap: _showWhoCanMessageSheet,
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.block_flipped,
                      title: l10n.blockedAccounts,
                      subtitle: l10n.manageBlockedUsers,
                      onTap: () => Navigator.pushNamed(context, AppRoutes.block),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionHeader(context, l10n.sectionSecurity),
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
                      icon: Icons.lock_reset_rounded,
                      title: l10n.changePassword,
                      subtitle: l10n.changePasswordSub,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.changePassword);
                      },
                    ),
                    _buildDivider(context),
                    _buildSwitchTile(
                      context,
                      icon: Icons.verified_user_outlined,
                      title: l10n.twoFactorAuth,
                      subtitle: l10n.twoFactorAuthSub,
                      value: _twoFactorAuth,
                      onChanged: _toggleTwoFactor,
                    ),
                    _buildDivider(context),
                    _buildSettingsTile(
                      context,
                      icon: Icons.devices_rounded,
                      title: l10n.loginSessions,
                      subtitle: l10n.loginSessionsSub,
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionHeader(context, l10n.sectionAccountManagement, isDanger: true),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.red.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _handleDeleteAccountTap,
                  icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                  label: Text(
                    l10n.deleteAccountTitle,
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
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isDanger ? AppColors.red.withValues(alpha: 0.9) : context.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    Color? titleColor,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final color = iconColor ?? AppColors.blue;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor ?? context.textPrimary,
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
        color: iconColor != null ? iconColor.withValues(alpha: 0.6) : context.textSubtle,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final color = iconColor ?? AppColors.blue;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
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
      trailing: AppSwitch(
        value: value,
        onChanged: onChanged,
      ),
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
}
