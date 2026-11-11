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
import '../../widgets/toast/app_toast.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String email;
  const ChangePasswordScreen({super.key, required this.email});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
      });

      try {
        final newPassword = _passwordController.text.trim();
        final currentLang = Localizations.localeOf(context).languageCode;

        final response = await http.post(
          Uri.parse(ApiConfig.resetPassword),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': widget.email,
            'password': newPassword,
            'language': currentLang,
          }),
        ).timeout(const Duration(seconds: 12));

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          AppToast.show(context, l10n.passwordResetSuccess, isError: false);
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.signIn,
            (route) => route.settings.name == AppRoutes.welcome,
          );
        } else {
          Map<String, dynamic> data = {};
          try {
            data = jsonDecode(response.body);
          } catch (_) {}
          final errorMsg = l10n.errorFromCode(
            data['code'],
            fallbackMessage: data['message'] ?? l10n.serverError,
          );
          AppToast.show(context, errorMsg, isError: true);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        if (e is SocketException || e is TimeoutException) {
          AppToast.show(context, l10n.noInternet, isError: true);
        } else {
          AppToast.show(context, l10n.serverError, isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20.r),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 24.w, right: 24.w, top: 12.h, bottom: 24.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 16.h),
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_open_outlined,
                        size: 72.r,
                        color: AppColors.blue,
                      ),
                    ),
                  ),

                  SizedBox(height: 28.h),

                  Text(
                    l10n.resetPassword,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    l10n.enterNewPassword,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: context.textMuted,
                    ),
                  ),
                  SizedBox(height: 32.h),
                  Text(
                    l10n.newPassword,
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
                      hintText: l10n.enterNewPassword,
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
                        return l10n.errorEmptyPassword;
                      }
                      if (value.length < 6) {
                        return l10n.errorShortPassword;
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 20.h),

                  Text(
                    l10n.confirmNewPassword,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8.h),
                  
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: l10n.enterConfirmNewPassword,
                      prefixIcon: Icon(Icons.lock_outline, size: 22.r),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 22.r,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.errorEmptyConfirmPassword;
                      }
                      if (value != _passwordController.text) {
                        return l10n.errorPasswordMismatch;
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 32.h),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      minimumSize: Size.fromHeight(56.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24.r,
                            width: 24.r,
                            child: const CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            l10n.resetPassword,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
