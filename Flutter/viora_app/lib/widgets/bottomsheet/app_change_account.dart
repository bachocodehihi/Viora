import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/session_service.dart';
import '../../services/socket_service.dart';
import '../../screens/setting/enter_password.dart';
import '../toast/app_toast.dart';
import '../app_avatar.dart';

class AppChangeAccountBottomSheet extends StatefulWidget {
  final String currentEmail;

  const AppChangeAccountBottomSheet({
    super.key,
    this.currentEmail = '',
  });

  static Future<void> show(
    BuildContext context, {
    String currentEmail = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppChangeAccountBottomSheet(
        currentEmail: currentEmail,
      ),
    );
  }

  @override
  State<AppChangeAccountBottomSheet> createState() => _AppChangeAccountBottomSheetState();
}

class _AppChangeAccountBottomSheetState extends State<AppChangeAccountBottomSheet> {
  List<Map<String, dynamic>> _accounts = [];
  String _activeEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final currentEmail = widget.currentEmail.isNotEmpty
        ? widget.currentEmail
        : (await SessionService.getUserEmail() ?? '');
    final currentUsername = await SessionService.getUsername();
    final currentAvatar = await SessionService.getAvatar();
    final currentUserId = await SessionService.getUserId();

    List<Map<String, dynamic>> saved = await SessionService.getSavedAccounts();

    if (currentEmail.isNotEmpty) {
      final exists = saved.any(
        (acc) => (acc['email'] as String? ?? '').trim().toLowerCase() == currentEmail.trim().toLowerCase(),
      );
      if (!exists) {
        await SessionService.saveAccountToSavedList(
          email: currentEmail,
          username: currentUsername,
          avatar: currentAvatar,
          userId: currentUserId,
        );
        saved = await SessionService.getSavedAccounts();
      }
    }

    if (mounted) {
      setState(() {
        _activeEmail = currentEmail;
        _accounts = saved;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchAccount(Map<String, dynamic> account) async {
    final email = (account['email'] as String? ?? '').trim();
    final name = (account['name'] as String? ?? account['username'] as String? ?? email.split('@').first).trim();

    if (email.toLowerCase() == _activeEmail.trim().toLowerCase()) {
      Navigator.pop(context);
      return;
    }

    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EnterPasswordScreen(
          isDeleteAccount: false,
          email: email,
        ),
      ),
    );

    if (verified == true && mounted) {
      SocketService.disconnect();
      Navigator.pop(context);
      AppToast.success(context, '${l10n.switchedToAccount} $name!');

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.main,
        (route) => false,
        arguments: email,
      );
    }
  }

  Future<void> _removeAccount(String email) async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.removeAccountTitle,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${l10n.account} $email ${l10n.removeAccountPrompt}',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: context.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionService.removeSavedAccount(email);
      await _loadAccounts();
    }
  }

  void _addAnotherAccount() {
    Navigator.pop(context);
    Navigator.pushNamed(context, AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Text(
                  l10n.changeAccount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
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
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      ..._accounts.map((acc) {
                        final email = acc['email'] as String? ?? '';
                        final isSelected = email.trim().toLowerCase() == _activeEmail.trim().toLowerCase();
                        final name = acc['name'] as String? ?? acc['username'] as String? ?? email.split('@').first;
                        final avatar = acc['avatar'] as String? ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.blue.withValues(alpha: 0.08)
                                : (context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.blue : context.borderTheme,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _switchAccount(acc),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: AppAvatar(
                              avatar: avatar,
                              name: name,
                              radius: 22,
                              fontSize: 16,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: context.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                            ),
                            trailing: isSelected
                                ? SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: Icon(
                                        Icons.check_rounded,
                                        color: AppColors.blue,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(Icons.close_rounded, size: 16, color: context.textMuted.withValues(alpha: 0.6)),
                                    onPressed: () => _removeAccount(email),
                                  ),
                          ),
                        );
                      }),

                      const SizedBox(height: 6),

                      Container(
                        decoration: BoxDecoration(
                          color: context.isDark ? const Color(0xFF161522) : Colors.grey.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderTheme),
                        ),
                        child: ListTile(
                          onTap: _addAnotherAccount,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_rounded, color: AppColors.blue, size: 22),
                          ),
                          title: Text(
                            l10n.addAnotherAccount,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: context.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            l10n.loginWithNewAccount,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(Icons.arrow_forward_ios_rounded, color: context.textMuted, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
