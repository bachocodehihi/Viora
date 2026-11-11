import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';

class EditAvatarScreen extends StatelessWidget {
  final String? currentAvatar;

  const EditAvatarScreen({super.key, this.currentAvatar});

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
        title: Text(l10n.avatar, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 20.sp)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 64.r,
              backgroundColor: AppColors.blue,
              child: const Icon(Icons.person, size: 64, color: Colors.white),
            ),
            SizedBox(height: 24.h),
            Text(l10n.changeAvatar, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: context.textPrimary)),
          ],
        ),
      ),
    );
  }
}
