import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_helper.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../widgets/toast/app_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() async {
    final l10n = context.l10n;

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _emailError = null;
        AppToast.clear();
      });

      try {
        final email = _emailController.text.trim();
        String currentLang = Localizations.localeOf(context).languageCode;

        final response = await http.post(
          Uri.parse(ApiConfig.sendOtp),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'purpose': 'reset',
            'language': currentLang,
          }),
        ).timeout(const Duration(seconds: 10));

        setState(() {
          _isLoading = false;
        });

        if (response.statusCode == 200) {
          if (!mounted) return;
          AppToast.show(context, l10n.verificationCodeSent, isError: false);
          Navigator.pushNamed(
            context,
            AppRoutes.verifyEmail,
            arguments: {
              'email': email,
              'isForgotPassword': true,
            },
          );
        } else {
          if (!mounted) return;
          final Map<String, dynamic> data = jsonDecode(response.body);
          String errorCode = data['code'] ?? '';

          if (errorCode == 'EMAIL_NOT_SIGNED_UP') {
            setState(() {
              _emailError = l10n.errorFromCode(errorCode);
            });
            _formKey.currentState!.validate();
          } else {
            final errorMsg = l10n.errorFromCode(errorCode, fallbackMessage: data['message']);
            AppToast.show(context, errorMsg, isError: true);
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.vpn_key_outlined,
                          size: 64.r,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),

                    Text(
                      l10n.resetPassword,
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),

                    Text(
                      l10n.forgotPasswordDescription,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: context.textMuted,
                      ),
                      textAlign: TextAlign.center,
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
                      onChanged: (_) {
                        if (_emailError != null) {
                          setState(() {
                            _emailError = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        hintText: l10n.enterEmail,
                        prefixIcon: Icon(Icons.email_outlined, size: 22.r),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.errorEmptyEmail;
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return l10n.errorInvalidEmail;
                        }
                        if (_emailError != null) {
                          return _emailError;
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
                              l10n.continuee,
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
      ),
    );
  }
}
