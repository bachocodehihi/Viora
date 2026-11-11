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
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/session_service.dart';
import '../../widgets/toast/app_toast.dart';

class EnterPasswordScreen extends StatefulWidget {
  final bool isDeleteAccount;
  final String? reason;
  final String? email;
  final String? targetAccountEmail;
  final String? targetAccountUsername;
  final String? customTitle;
  final String? customSubtitle;
  final Future<bool> Function(String password)? onVerifyPassword;

  const EnterPasswordScreen({
    super.key,
    this.isDeleteAccount = false,
    this.reason,
    this.email,
    this.targetAccountEmail,
    this.targetAccountUsername,
    this.customTitle,
    this.customSubtitle,
    this.onVerifyPassword,
  });

  @override
  State<EnterPasswordScreen> createState() => _EnterPasswordScreenState();
}

class _EnterPasswordScreenState extends State<EnterPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _userEmail = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (widget.email != null && widget.email!.isNotEmpty) {
      _userEmail = widget.email!;
    } else {
      _userEmail = (await SessionService.getUserEmail()) ?? '';
    }
    _userId = await SessionService.getUserId();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final password = _passwordController.text.trim();
    final l10n = context.l10n;

    if (password.isEmpty) {
      AppToast.show(
        context,
        l10n.enterPasswordConfirmReq,
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {

      if (widget.isDeleteAccount) {
        final token = await SessionService.getToken();
        final res = await http.post(
          Uri.parse(ApiConfig.requestDeleteAccount),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'email': _userEmail,
            'userId': _userId,
            'password': password,
            'reason': widget.reason ?? '',
          }),
        );

        final data = jsonDecode(res.body);
        if (res.statusCode == 200 && data['success'] == true) {
          if (mounted) {
            AppToast.show(
              context,
              data['message'] ?? l10n.confirmSuccess,
            );

            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            final errorMsg = l10n.errorFromCode(
              data['code'],
              fallbackMessage: data['message'] ?? l10n.incorrectPassword,
            );
            AppToast.show(
              context,
              errorMsg,
              isError: true,
            );
          }
        }
      } 

      else if (widget.onVerifyPassword != null) {
        final success = await widget.onVerifyPassword!(password);
        if (success && mounted) {
          Navigator.pop(context, true);
        }
      } 

      else {
        final currentLang = Localizations.localeOf(context).languageCode;
        final deviceName = await DeviceService.getDeviceName();
        final deviceId = await DeviceService.getDeviceId();

        final res = await http.post(
          Uri.parse(ApiConfig.login),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _userEmail,
            'password': password,
            'deviceName': deviceName,
            'deviceId': deviceId,
            'language': currentLang,
          }),
        );

        final data = jsonDecode(res.body);
        if (res.statusCode == 200) {
          if (data['requiresTwoFactor'] == true) {
            if (!mounted) return;
            AppToast.show(context, context.l10n.verificationCodeSent);
            final verified = await Navigator.pushNamed(
              context,
              AppRoutes.verifyEmail,
              arguments: {
                'email': data['email']?.toString() ?? _userEmail,
                'isTwoFactorLogin': true,
                'twoFactorToken': data['twoFactorToken']?.toString() ?? '',
                'deviceName': deviceName,
                'deviceId': deviceId,
                'returnResultOnVerify': true,
              },
            );
            if (verified == true && mounted) {
              Navigator.pop(context, true);
            }
            return;
          }

          final token = data['token'] as String?;
          final account = data['account'] as Map<String, dynamic>?;

          await SessionService.saveSession(
            _userEmail,
            token: token,
            userId: account?['_id']?.toString() ?? account?['id']?.toString(),
            username: account?['username']?.toString(),
            avatar: account?['avatar']?.toString(),
            qrCode: account?['qrCode']?.toString(),
          );
          unawaited(NotificationService.syncTokenWithBackend());

          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            final errorMsg = l10n.errorFromCode(
              data['code'],
              fallbackMessage: data['message'] ?? l10n.incorrectPassword,
            );
            AppToast.show(
              context,
              errorMsg,
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          l10n.connectionError,
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final appBarTitle = widget.customTitle ?? l10n.enterPassword;
    final headingText = widget.customTitle ?? l10n.enterPassword;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headingText,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              if (widget.customSubtitle != null && widget.customSubtitle!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  widget.customSubtitle!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: context.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: 24.h),

              Text(
                l10n.yourPassword,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(fontSize: 15.sp, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.enterPassword,
                  hintStyle: TextStyle(fontSize: 14.sp, color: context.textMuted),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: context.textMuted, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: context.textMuted,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: context.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    borderSide: const BorderSide(
                      color: AppColors.blue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32.h),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size.fromHeight(52.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        l10n.confirm,
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
