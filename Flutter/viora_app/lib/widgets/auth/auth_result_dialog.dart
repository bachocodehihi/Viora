import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';

class AuthResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onConfirm;

  const AuthResultDialog({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    this.buttonText,
    this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isSuccess,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isSuccess,
      builder: (ctx) => AuthResultDialog(
        isSuccess: isSuccess,
        title: title,
        message: message,
        buttonText: buttonText,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dialogBg = context.cardBg;

    return PopScope(
      canPop: !isSuccess,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop();
        if (onConfirm != null) {
          onConfirm!();
        }
      },
      child: Dialog(
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
                color: (isSuccess ? AppColors.green : AppColors.red).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 44.r,
                color: isSuccess ? AppColors.green : AppColors.red,
              ),
            ),
            SizedBox(height: 20.h),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 10.h),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: context.textMuted,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) {
                  onConfirm!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? AppColors.blue : context.dividerTheme,
                foregroundColor: isSuccess ? Colors.white : theme.colorScheme.onSurface,
                elevation: 0,
                minimumSize: Size.fromHeight(50.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                buttonText ?? (isSuccess ? l10n.loginNow : l10n.close),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
