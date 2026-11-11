import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../../widgets/language_switcher.dart';

class WellcomeScreen extends StatefulWidget {
  const WellcomeScreen({super.key});

  @override
  State<WellcomeScreen> createState() => _WellcomeScreenState();
}

class _WellcomeScreenState extends State<WellcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.isDark
                ? [
                    const Color(0xFF0F0E17),
                    const Color(0xFF1E2836),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFEBF1F9),
                  ],
          ),
        ),
        child: SafeArea(
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
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset('assets/icons/logo.png', width: 28.r, height: 28.r),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Viora',
                                    style: TextStyle(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.bold,
                                      color: context.textPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const LanguageSwitcher(),
                            ],
                          ),

                          const Spacer(),
                          
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.scale(
                                  scale: 0.8 + (value * 0.2),
                                  child: child,
                                ),
                              );
                            },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 260.r,
                                  height: 260.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.blue.withValues(alpha: context.isDark ? 0.2 : 0.15),
                                        AppColors.blue.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 220.r,
                                  height: 220.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.blue.withValues(alpha: context.isDark ? 0.2 : 0.12),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 170.r,
                                  height: 170.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.blue.withValues(alpha: context.isDark ? 0.15 : 0.1),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 120.r,
                                  height: 120.r,
                                  decoration: BoxDecoration(
                                    color: AppColors.blue.withValues(alpha: context.isDark ? 0.1 : 0.08),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blue.withValues(alpha: context.isDark ? 0.15 : 0.12),
                                        blurRadius: 30.r,
                                        spreadRadius: 2.r,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(22.r),
                                    child: Image.asset(
                                      'assets/icons/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 20.h,
                                  right: 10.w,
                                  child: _buildFloatingStatCard(
                                    icon: Icons.chat_bubble_rounded,
                                    color: AppColors.blue,
                                    text: 'Connect',
                                  ),
                                ),
                                Positioned(
                                  bottom: 30.h,
                                  left: 0,
                                  child: _buildFloatingStatCard(
                                    icon: Icons.photo_library_rounded,
                                    color: AppColors.pink,
                                    text: 'Moments',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.welcome,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),

                              SizedBox(height: 12.h),
                              
                              Text(
                                l10n.chatAndShareMoments,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: context.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 32.h),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.signIn);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blue,
                                  foregroundColor: AppColors.white,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  minimumSize: Size.fromHeight(56.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                ),
                                child: Text(
                                  l10n.signIn,
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              SizedBox(height: 16.h),
                              
                              OutlinedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.signUp);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: context.isDark
                                        ? AppColors.white.withValues(alpha: 0.3)
                                        : AppColors.blue.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  minimumSize: Size.fromHeight(56.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                ),
                                child: Text(
                                  l10n.createAnAccount,
                                  style: TextStyle(
                                    color: context.isDark ? AppColors.white : AppColors.blue,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 16.h),
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

  Widget _buildFloatingStatCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: context.cardBg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: context.borderTheme,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.06),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16.r),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

