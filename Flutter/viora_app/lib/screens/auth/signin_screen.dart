import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/theme_helper.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../services/device_service.dart';
import '../../widgets/toast/app_toast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final l10n = context.l10n;
    final currentLang = Localizations.localeOf(context).languageCode;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final deviceName = await DeviceService.getDeviceName();
      final deviceId = await DeviceService.getDeviceId();

      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceName': deviceName,
          'deviceId': deviceId,
          'language': currentLang,
        }),
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _isLoading = false;
      });

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200) {
        if (!mounted) return;
        if (data['requiresTwoFactor'] == true) {
          AppToast.show(context, l10n.verificationCodeSent);
          await Navigator.pushNamed(
            context,
            AppRoutes.verifyEmail,
            arguments: {
              'email': data['email']?.toString() ?? email,
              'isTwoFactorLogin': true,
              'twoFactorToken': data['twoFactorToken']?.toString() ?? '',
              'deviceName': deviceName,
              'deviceId': deviceId,
            },
          );
          return;
        }

        AppToast.success(context, l10n.signInSuccess);

        final token = data['token'] as String?;
        final account = data['account'] as Map<String, dynamic>?;

        await SessionService.saveSession(
          email,
          token: token,
          userId: account?['_id']?.toString() ?? account?['id']?.toString(),
          username: account?['username']?.toString(),
          avatar: account?['avatar']?.toString(),
          qrCode: account?['qrCode']?.toString(),
        );

        unawaited(NotificationService.syncTokenWithBackend());

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.main,
            (route) => false,
            arguments: email,
          );
        }
      } else {
        if (!mounted) return;
        final errorCode = data['code'];
        final localizedError = l10n.errorFromCode(
          errorCode,
          fallbackMessage: data['message'] ?? (response.statusCode == 401 ? l10n.incorrectUsernameOrPassword : l10n.signInFailed),
        );
        AppToast.error(context, localizedError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e is SocketException || e is TimeoutException) {
        AppToast.error(context, l10n.noInternet);
      } else {
        AppToast.error(context, l10n.serverError);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final l10n = context.l10n;
    FocusScope.of(context).unfocus();

    final currentLang = Localizations.localeOf(context).languageCode;

    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final deviceName = await DeviceService.getDeviceName();
      final deviceId = await DeviceService.getDeviceId();

      final response = await http.post(
        Uri.parse(ApiConfig.googleSignIn),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
          'deviceName': deviceName,
          'deviceId': deviceId,
          'language': currentLang,
        }),
      ).timeout(const Duration(seconds: 15));

      setState(() {
        _isLoading = false;
      });

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && data['success'] == true) {
        final isNewUser = data['isNewUser'] == true;

        if (isNewUser) {
          if (!mounted) return;
          context.read<SignUpProvider>().reset();
          context.read<SignUpProvider>().setEmail(googleUser.email);
          if (googleUser.displayName != null && googleUser.displayName!.trim().isNotEmpty) {
            context.read<SignUpProvider>().setUsername(googleUser.displayName!.trim());
          }

          AppToast.show(context, l10n.verificationCodeSent);

          await Navigator.pushNamed(
            context,
            AppRoutes.verifyEmail,
            arguments: googleUser.email,
          );
        } else if (data['requiresTwoFactor'] == true) {
          if (!mounted) return;
          AppToast.show(context, l10n.verificationCodeSent);
          await Navigator.pushNamed(
            context,
            AppRoutes.verifyEmail,
            arguments: {
              'email': data['email']?.toString() ?? googleUser.email,
              'isTwoFactorLogin': true,
              'twoFactorToken': data['twoFactorToken']?.toString() ?? '',
              'deviceName': deviceName,
              'deviceId': deviceId,
            },
          );
        } else {
          if (!mounted) return;
          AppToast.success(context, l10n.signInSuccess);

          final token = data['token'] as String?;
          final account = data['account'] as Map<String, dynamic>?;

          await SessionService.saveSession(
            googleUser.email,
            token: token,
            userId: account?['_id']?.toString() ?? account?['id']?.toString(),
            username: account?['username']?.toString(),
            avatar: account?['avatar']?.toString(),
            qrCode: account?['qrCode']?.toString(),
          );

          unawaited(NotificationService.syncTokenWithBackend());

          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.main,
              (route) => false,
              arguments: googleUser.email,
            );
          }
        }
      } else {
        if (!mounted) return;
        final localizedError = l10n.errorFromCode(
          data['code'],
          fallbackMessage: data['message'] ?? l10n.signInFailed,
        );
        AppToast.error(context, localizedError);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (e is SocketException || e is TimeoutException) {
        AppToast.error(context, l10n.noInternet);
      } else {
        AppToast.error(context, l10n.signInFailed);
      }
    }
  }

  void _handleBack() {
    FocusScope.of(context).unfocus();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.welcome,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20.r),
              onPressed: _handleBack,
            ),
          ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 12.h,
                        bottom: 24.h,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 16.h),
                            Text(
                              l10n.signIn,
                              style: TextStyle(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 32.h),
                            
                            Text(
                              l10n.email,
                              style: TextStyle(
                                fontSize: 14.sp, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8.h),
                            
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: l10n.enterEmail,
                                prefixIcon: Icon(Icons.email_outlined, size: 22.r),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.pleaseEnterEmail;
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return l10n.errorInvalidEmail;
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 20.h),

                            Text(
                              l10n.password,
                              style: TextStyle(
                                fontSize: 14.sp, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 8.h),

                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: l10n.enterPassword,
                                prefixIcon: Icon(Icons.lock_outline, size: 22.r),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    size: 22.r,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.pleaseEnterPassword;
                                }
                                if (value.length < 6) {
                                  return l10n.errorShortPassword;
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: 20.h),

                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, AppRoutes.forgotPassword);
                                },
                                child: Text(
                                  l10n.forgotPassword,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 20.h),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                minimumSize: Size.fromHeight(56.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24.r,
                                      height: 24.r,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      l10n.signIn,
                                      style: TextStyle(
                                        fontSize: 16.sp, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.white,
                                      ),
                                    ),
                            ),

                            const Spacer(),

                            SizedBox(height: 20.h),

                            Row(
                              children: [
                                Expanded(child: Divider(color: context.dividerTheme)),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Text(
                                    l10n.continueWith,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: context.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: context.dividerTheme)),
                              ],
                            ),

                            SizedBox(height: 20.h),

                            _buildGoogleButton(
                              onTap: _isLoading ? () {} : _handleGoogleSignIn,
                            ),

                            SizedBox(height: 24.h),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.dontHaveAccount,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: context.textMuted,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacementNamed(context, AppRoutes.signUp);
                                  },
                                  child: Text(
                                    l10n.signUp,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppColors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _buildGoogleButton({
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: context.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 8.r,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/google.png',
                  width: 22.r,
                  height: 22.r,
                ),
                SizedBox(width: 12.w),
                Text(
                  l10n.signInWithGoogle,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
