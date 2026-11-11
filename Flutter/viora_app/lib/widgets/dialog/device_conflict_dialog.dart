import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';

class DeviceConflictDialog extends StatelessWidget {
  final String deviceName;
  final VoidCallback onConfirm;

  const DeviceConflictDialog({
    super.key,
    required this.deviceName,
    required this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String deviceName,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: DeviceConflictDialog(
          deviceName: deviceName,
          onConfirm: onConfirm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogBg = context.cardBg;
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.devices_other_rounded,
                size: 40.r,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              l10n.deviceConflictTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: 12.h),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['Inter', 'Roboto', 'sans-serif'],
                  fontSize: 14.sp,
                  color: context.textMuted,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: l10n.deviceConflictMessage1,
                  ),
                  TextSpan(
                    text: deviceName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                      fontSize: 15.sp,
                    ),
                  ),
                  TextSpan(
                    text: l10n.deviceConflictMessage2,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.signInAgain,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
