import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_helper.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';
import '../../widgets/auth/auth_result_dialog.dart';

class SetupPasswordScreen extends StatefulWidget {
  final String email;
  const SetupPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetupPasswordScreen> createState() => _SetupPasswordScreenState();
}

class _SetupPasswordScreenState extends State<SetupPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasValidated = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() {
      _hasValidated = true;
    });

    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SignUpProvider>();
    provider.setPassword(_passwordController.text.trim());

    setState(() {
      _isLoading = true;
    });

    final result = await provider.submitRegistration();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    final l10n = context.l10n;

    if (result['success'] == true) {
      await AuthResultDialog.show(
        context: context,
        isSuccess: true,
        title: l10n.signUpSuccessTitle,
        message: l10n.signUpSuccessMessage,
        buttonText: l10n.signInNow,
        onConfirm: () {
          provider.reset();

          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.signIn,
            (route) => route.settings.name == AppRoutes.welcome,
          );
        },
      );
    } else {
      final errorMsg = l10n.errorFromCode(
        result['code'],
        fallbackMessage: result['message'] ?? l10n.signUpFailedMessage,
      );

      await AuthResultDialog.show(
        context: context,
        isSuccess: false,
        title: l10n.signUpFailedTitle,
        message: errorMsg,
        buttonText: l10n.close,
      );
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: 20.r),
            onPressed: () {
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
                            Center(
                              child: Container(
                                padding: EdgeInsets.all(24.r),
                                decoration: BoxDecoration(
                                  color: AppColors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.lock_outline,
                                  size: 72.r,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                            SizedBox(height: 28.h),
                            Text(
                              l10n.password,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              l10n.setupPasswordDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: context.textMuted,
                              ),
                            ),
                            SizedBox(height: 32.h),
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
                              onChanged: (value) {
                                if (_hasValidated) {
                                  _formKey.currentState!.validate();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: l10n.password,
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
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.pleaseEnterPassword;
                                }
                                if (value.trim().length < 6) {
                                  return l10n.errorShortPassword;
                                }
                                if (_confirmPasswordController.text.trim().isNotEmpty &&
                                    value.trim() != _confirmPasswordController.text.trim()) {
                                  return l10n.errorPasswordMismatch;
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              l10n.confirmPassword,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              onChanged: (value) {
                                if (_hasValidated) {
                                  _formKey.currentState!.validate();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: l10n.confirmPassword,
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
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.pleaseEnterConfirmPassword;
                                }
                                if (value.trim() != _passwordController.text.trim()) {
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
                                      l10n.continuee,
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
            },
          ),
        ),
      ),
    );
  }
}
