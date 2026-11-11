import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/theme_helper.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';

class SetupNameScreen extends StatefulWidget {
  final String email;
  const SetupNameScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetupNameScreen> createState() => _SetupNameScreenState();
}

class _SetupNameScreenState extends State<SetupNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final savedName = context.read<SignUpProvider>().username;
    if (savedName != null && savedName.isNotEmpty) {
      _usernameController.text = savedName;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<SignUpProvider>().setUsername(_usernameController.text.trim());
      Navigator.pushNamed(
        context,
        AppRoutes.setupBirthday,
        arguments: widget.email,
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
              context.read<SignUpProvider>().reset();
              Navigator.popUntil(
                context,
                (route) => route.settings.name == AppRoutes.signUp || route.settings.name == AppRoutes.signIn || route.isFirst,
              );
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
                                  Icons.account_circle_outlined,
                                  size: 72.r,
                                  color: AppColors.blue,
                                ),
                              ),
                            ),
                            SizedBox(height: 28.h),
                            Text(
                              l10n.username,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              l10n.setupUsernameDescription,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: context.textMuted,
                              ),
                            ),
                            SizedBox(height: 32.h),
                            Text(
                              l10n.username,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            TextFormField(
                              controller: _usernameController,
                              keyboardType: TextInputType.text,
                              decoration: InputDecoration(
                                hintText: l10n.enterUsername,
                                prefixIcon: Icon(Icons.person_outline, size: 22.r),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return l10n.pleaseEnterUsername;
                                }
                                if (value.trim().length < 3) {
                                  return l10n.errorShortUsername;
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 32.h),
                            ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blue,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                minimumSize: Size.fromHeight(56.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              ),
                              child: Text(
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
