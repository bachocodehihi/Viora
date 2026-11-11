import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';

class EditCoverImageScreen extends StatelessWidget {
  final String? currentCover;

  const EditCoverImageScreen({super.key, this.currentCover});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.coverPhoto, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 20.sp)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 140.h,
              width: 0.85.sw,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: const Icon(Icons.image, size: 48, color: AppColors.blue),
            ),
            SizedBox(height: 24.h),
            Text(l10n.changeCoverPhoto, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }
}
