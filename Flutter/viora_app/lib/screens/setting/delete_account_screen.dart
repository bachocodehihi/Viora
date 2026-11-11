import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../services/session_service.dart';
import '../../widgets/toast/app_toast.dart';
import 'enter_password.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {

  bool _isPendingReview = false;
  bool _isLoadingStatus = true;

  String _userEmail = '';
  String? _userId;

  int _selectedReasonIndex = 0;
  final TextEditingController _customReasonController = TextEditingController();

  DateTime? _scheduledDeletionTime;
  Timer? _scheduledTimer;
  Duration _remainingDuration = Duration.zero;
  bool _isCancelling = false;

  List<String> _getReasons(Language l10n) => [
    l10n.deleteReasonNoLongerUse,
    l10n.deleteReasonPrivacy,
    l10n.deleteReasonAnotherAccount,
    l10n.deleteReasonTechnical,
    l10n.deleteReasonNotifications,
    l10n.deleteReasonOther,
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _scheduledTimer?.cancel();
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    _userEmail = (await SessionService.getUserEmail()) ?? '';
    _userId = await SessionService.getUserId();

    await _checkDeletionStatus();
  }

  bool _isHandlingDeletion = false;

  Future<void> _handleAccountDeleted() async {
    if (_isHandlingDeletion) return;
    _isHandlingDeletion = true;
    _scheduledTimer?.cancel();

    if (!mounted) return;

    final l10n = context.l10n;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.deleteAccountTitle,
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          l10n.deleteAccountExpiredDesc,
          style: TextStyle(color: context.textMuted, fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.ok, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    await SessionService.clearSession(removeFromSaved: true);
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
    }
  }

  Future<void> _checkDeletionStatus() async {
    try {
      final token = await SessionService.getToken();
      final res = await http.post(
        Uri.parse(ApiConfig.getDeletionStatus),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': _userEmail,
          'userId': _userId,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {

          if (data['isDeleted'] == true || data['isExpired'] == true) {
            if (mounted) {
              setState(() => _isLoadingStatus = false);
              _handleAccountDeleted();
            }
            return;
          }

          if (data['deletionRequested'] == true) {
            if (data['deletionScheduledAt'] != null) {
              _scheduledDeletionTime = DateTime.tryParse(data['deletionScheduledAt'].toString());
            }

            if (_scheduledDeletionTime != null && _scheduledDeletionTime!.isBefore(DateTime.now())) {
              if (mounted) {
                setState(() => _isLoadingStatus = false);
                _handleAccountDeleted();
              }
              return;
            }

            _startScheduledCountdown();
            if (mounted) {
              setState(() {
                _isPendingReview = true;
                _isLoadingStatus = false;
              });
            }
            return;
          }
        }
      } else if (res.statusCode == 404) {

        if (mounted) {
          setState(() => _isLoadingStatus = false);
          _handleAccountDeleted();
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking deletion status: $e');
    }

    if (mounted) {
      setState(() {
        _isPendingReview = false;
        _isLoadingStatus = false;
      });
    }
  }

  void _startScheduledCountdown() {
    _scheduledTimer?.cancel();
    if (_scheduledDeletionTime == null) {
      _remainingDuration = const Duration(minutes: 2);
    } else {
      final now = DateTime.now();
      if (_scheduledDeletionTime!.isAfter(now)) {
        _remainingDuration = _scheduledDeletionTime!.difference(now);
      } else {
        _remainingDuration = Duration.zero;
      }
    }

    if (_remainingDuration <= Duration.zero) {
      _handleAccountDeleted();
      return;
    }

    _scheduledTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingDuration.inSeconds > 0) {
          _remainingDuration = _remainingDuration - const Duration(seconds: 1);
        } else {
          _remainingDuration = Duration.zero;
          timer.cancel();
          _handleAccountDeleted();
        }
      });
    });
  }

  Future<void> _onReasonSubmitted() async {
    final l10n = context.l10n;
    final reasons = _getReasons(l10n);
    String reason = reasons[_selectedReasonIndex];
    if (_selectedReasonIndex == reasons.length - 1) {
      final custom = _customReasonController.text.trim();
      if (custom.isNotEmpty) {
        reason = custom;
      }
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EnterPasswordScreen(
          isDeleteAccount: true,
          reason: reason,
          email: _userEmail,
        ),
      ),
    );

    if (result == true) {
      await _checkDeletionStatus();
    }
  }

  Future<void> _cancelDeletionRequest() async {
    final l10n = context.l10n;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.cancelDeletionTitle,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          l10n.cancelDeletionMessage,
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              l10n.close,
              style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              l10n.confirmCancel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final token = await SessionService.getToken();
      final res = await http.post(
        Uri.parse(ApiConfig.cancelDeleteAccount),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': _userEmail,
          'userId': _userId,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _scheduledTimer?.cancel();
        if (mounted) {
          AppToast.show(
            context,
            l10n.deletionCancelledSuccess,
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          final errorMsg = l10n.errorFromCode(
            data['code'],
            fallbackMessage: data['message'] ?? l10n.failedToCancelDeletion,
          );
          AppToast.show(
            context,
            errorMsg,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, l10n.requestConnectionError, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  void _signOut() async {
    await SessionService.clearSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcome, (route) => false);
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours : $minutes : $seconds';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.deleteAccountTitle,
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
        child: _isLoadingStatus
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: _isPendingReview
                    ? _buildStepPending(context)
                    : _buildStepReason(context),
              ),
      ),
    );
  }

  Widget _buildStepReason(BuildContext context) {
    final l10n = context.l10n;
    final reasons = _getReasons(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.whyDeleteAccount,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          l10n.whyDeleteAccountDesc,
          style: TextStyle(
            fontSize: 13.sp,
            color: context.textMuted,
            height: 1.4,
          ),
        ),
        SizedBox(height: 20.h),

        Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderTheme),
          ),
          child: Column(
            children: List.generate(reasons.length, (index) {
              final isSelected = _selectedReasonIndex == index;
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedReasonIndex = index;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.blue : context.borderTheme,
                                width: isSelected ? 6 : 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              reasons[index],
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? context.textPrimary : context.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (index < reasons.length - 1)
                    Divider(height: 1, indent: 16, endIndent: 16, color: context.borderTheme),
                ],
              );
            }),
          ),
        ),

        if (_selectedReasonIndex == reasons.length - 1) ...[
          SizedBox(height: 16.h),
          TextField(
            controller: _customReasonController,
            maxLines: 3,
            style: TextStyle(fontSize: 14.sp, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.describeReasonHint,
              hintStyle: TextStyle(fontSize: 13.sp, color: context.textMuted),
              filled: true,
              fillColor: context.cardBg,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.borderTheme),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.borderTheme),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
              ),
            ),
          ),
        ],

        SizedBox(height: 28.h),

        ElevatedButton(
          onPressed: _onReasonSubmitted,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size.fromHeight(52.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          ),
          child: Text(
            l10n.continueText,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStepPending(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 20.h),
        Container(
          width: 100.r,
          height: 100.r,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.hourglass_top_rounded,
            size: 52.r,
            color: Colors.amber.shade700,
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          l10n.requestSubmittedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          l10n.deleteAccountPendingDescReview,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5.sp,
            color: context.textMuted,
            height: 1.5,
          ),
        ),
        SizedBox(height: 28.h),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    l10n.remainingReviewTime,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatDuration(_remainingDuration),
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: Colors.amber.shade700,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.deleteAccountWarning2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 36.h),

        ElevatedButton.icon(
          onPressed: _isCancelling ? null : _cancelDeletionRequest,
          icon: const Icon(Icons.undo_rounded, size: 20),
          label: _isCancelling
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  l10n.cancelDeletionRequestBtn,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: Size.fromHeight(52.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          ),
        ),

        SizedBox(height: 14.h),

        OutlinedButton.icon(
          onPressed: _signOut,
          icon: Icon(Icons.logout_rounded, size: 18, color: context.textMuted),
          label: Text(
            l10n.signOutFromDevice,
            style: TextStyle(fontSize: 14.sp, color: context.textMuted, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.borderTheme),
            minimumSize: Size.fromHeight(50.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          ),
        ),

        SizedBox(height: 16.h),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.backToSettings,
            style: TextStyle(fontSize: 13.sp, color: AppColors.blue, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
