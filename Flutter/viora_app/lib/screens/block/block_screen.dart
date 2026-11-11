import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/toast/app_toast.dart';
import '../../l10n/language.dart';

class BlockScreen extends StatefulWidget {
  const BlockScreen({super.key});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    final users = await ProfileService.loadBlockedAccounts();
    if (mounted) {
      setState(() {
        _blockedUsers = users;
        _isLoading = false;
      });
    }
  }

  void _confirmUnblock(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? l10n.user;
    final userId = user['id']?.toString() ?? user['userId']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: dlgCtx.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${dlgCtx.l10n.unblock} $name?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: dlgCtx.textPrimary,
          ),
        ),
        content: Text(
          '$name ${dlgCtx.l10n.unblockDialogMessage}',
          style: TextStyle(fontSize: 13.5, color: dlgCtx.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(dlgCtx.l10n.cancel, style: TextStyle(color: dlgCtx.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dlgCtx);
              final success = await ProfileService.unblockAccount(userId);
              if (mounted) {
                if (success) {
                  setState(() {
                    _blockedUsers.removeWhere((u) =>
                        (u['id']?.toString() ?? u['userId']?.toString()) == userId);
                  });
                  AppToast.success(
                    context,
                    '${l10n.unblockedSuccess} $name',
                  );
                } else {
                  AppToast.error(
                    context,
                    l10n.failedToUnblockUser,
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
              dlgCtx.l10n.unblock,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.blockedAccounts,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 19,
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
        child: RefreshIndicator(
          onRefresh: _loadBlockedUsers,
          color: AppColors.blue,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
              : _blockedUsers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shield_outlined,
                                  size: 48,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noBlockedAccounts,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  l10n.noBlockedAccountsDesc,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: context.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _blockedUsers.length,
                      itemBuilder: (context, index) {
                        final user = _blockedUsers[index];
                        final name = user['name']?.toString() ?? l10n.user;
                        final bio = user['bio']?.toString() ?? user['username']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: AppAvatar(
                              avatar: user['avatar'],
                              name: name,
                              color: AppColors.blue,
                              radius: 22,
                              enableViewer: false,
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                                color: context.textPrimary,
                              ),
                            ),
                            subtitle: bio.isNotEmpty
                                ? Text(
                                    bio,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: context.textMuted),
                                  )
                                : null,
                            trailing: OutlinedButton(
                              onPressed: () => _confirmUnblock(user),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.blue,
                                side: const BorderSide(color: AppColors.blue),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                l10n.unblock,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
