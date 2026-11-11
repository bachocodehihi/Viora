import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../widgets/toast/app_toast.dart';
import '../../widgets/auth/app_agreement_tile.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _agreeTerms = false;
  bool _agreePrivacy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SignUpProvider>().reset();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  String? _emailError;

  void _submit() async {
    final l10n = context.l10n;
    if (_formKey.currentState!.validate()) {
      if (!_agreeTerms || !_agreePrivacy) {
        AppToast.show(context, l10n.errorAcceptTerms, isError: true);
        return;
      }
      
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
            'purpose': 'signup',
            'language': currentLang,
          }),
        ).timeout(const Duration(seconds: 10));
        
        setState(() {
          _isLoading = false;
        });
        
        if (response.statusCode == 200) {
          if (!mounted) return;
          context.read<SignUpProvider>().setEmail(email);
          AppToast.show(context, l10n.verificationCodeSent);
          await Navigator.pushNamed(
            context,
            AppRoutes.verifyEmail,
            arguments: email,
          );

          if (mounted) {
            context.read<SignUpProvider>().reset();
          }
        } else {
          if (!mounted) return;
          final Map<String, dynamic> data = jsonDecode(response.body);
          String errorCode = data['code'] ?? '';
          
          if (errorCode == 'EMAIL_ALREADY_SIGNED_UP') {
            setState(() {
              _emailError = l10n.emailAlreadySignedUp;
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
    final theme = Theme.of(context);

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
                            SizedBox(height: 10.h),
                            Text(
                              l10n.signUp,
                              style: TextStyle(
                                fontSize: 32.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              l10n.signUpDescription,
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),

                            SizedBox(height: 24.h),

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
                              onChanged: (val) {
                                if (_emailError != null) {
                                  setState(() {
                                    _emailError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: l10n.enterEmail,
                                errorText: _emailError,
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

                            AppAgreementTile(
                              value: _agreeTerms,
                              prefixText: l10n.iAgreeTo,
                              linkText: l10n.termsOfService,
                              onChanged: (val) {
                                setState(() {
                                  _agreeTerms = val ?? false;
                                });
                              },
                              onLinkTap: () {
                                Navigator.pushNamed(context, AppRoutes.termsOfService);
                              },
                            ),

                            SizedBox(height: 8.h),

                            AppAgreementTile(
                              value: _agreePrivacy,
                              prefixText: l10n.iAgreeTo,
                              linkText: l10n.privacyPolicy,
                              onChanged: (val) {
                                setState(() {
                                  _agreePrivacy = val ?? false;
                                });
                              },
                              onLinkTap: () {
                                Navigator.pushNamed(context, AppRoutes.privacyPolicy);
                              },
                            ),

                            SizedBox(height: 24.h),

                            ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.7),
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
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    l10n.continuee,
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  l10n.alreadyHaveAccount,
                                  style: TextStyle(
                                    fontSize: 14.sp, 
                                    color: Colors.grey,
                                  ),
                                ),

                                GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacementNamed(context, AppRoutes.signIn);
                                  },
                                  child: Text(
                                    l10n.signIn,
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
    );
  }
}
