import 'package:flutter/material.dart';
import '../../config/theme_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import '../../widgets/toast/app_toast.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';

class SetupGenderScreen extends StatefulWidget {
  final String email;
  const SetupGenderScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetupGenderScreen> createState() => _SetupGenderScreenState();
}

class _SetupGenderScreenState extends State<SetupGenderScreen> {
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _selectedGender = context.read<SignUpProvider>().gender;
  }

  void _submit() {
    final l10n = context.l10n;
    if (_selectedGender == null) {
      AppToast.show(context, l10n.pleaseSelectGender, isError: true);
      return;
    }

    context.read<SignUpProvider>().setGender(_selectedGender!);

    Navigator.pushNamed(
      context,
      AppRoutes.setupAvatar,
      arguments: widget.email,
    );
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
                                Icons.wc_outlined,
                                size: 72.r,
                                color: AppColors.blue,
                              ),
                            ),
                          ),
                          SizedBox(height: 28.h),
                          Text(
                            l10n.gender,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            l10n.setupGenderDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: context.textMuted,
                            ),
                          ),
                          SizedBox(height: 32.h),
                          Text(
                            l10n.selectGender,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _buildGenderCard(
                            genderKey: 'male',
                            label: l10n.male,
                            icon: Icons.man_outlined,
                            activeColor: AppColors.blue,
                          ),
                          SizedBox(height: 12.h),
                          _buildGenderCard(
                            genderKey: 'female',
                            label: l10n.female,
                            icon: Icons.woman_outlined,
                            activeColor: AppColors.pink,
                          ),
                          SizedBox(height: 12.h),
                          _buildGenderCard(
                            genderKey: 'other',
                            label: l10n.other,
                            icon: Icons.person_outline,
                            activeColor: AppColors.purple,
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard({
    required String genderKey,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _selectedGender == genderKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = genderKey;
        });
      },
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : context.cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24.r,
              color: isSelected ? activeColor : context.textMuted,
            ),
            SizedBox(width: 12.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : context.textPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 24.r,
                color: activeColor,
              ),
          ],
        ),
      ),
    );
  }
}
