import 'dart:io';
import 'package:flutter/material.dart';
import '../../config/theme_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../l10n/language.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';

class SetupAvatarScreen extends StatefulWidget {
  final String email;
  const SetupAvatarScreen({
    super.key,
    required this.email,
  });

  @override
  State<SetupAvatarScreen> createState() => _SetupAvatarScreenState();
}

class _SetupAvatarScreenState extends State<SetupAvatarScreen> {
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = context.read<SignUpProvider>().avatarFile;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showPickerBottomSheet(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dialogBg = context.cardBg;

    showModalBottomSheet(
      context: context,
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: 12.h, 
              bottom: 24.h, 
              left: 24.w, 
              right: 24.w
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: context.dividerTheme,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  l10n.chooseAvatar,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildPickerCard(
                        context: context,
                        icon: Icons.camera_alt_outlined,
                        label: l10n.takePhoto,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildPickerCard(
                        context: context,
                        icon: Icons.image_outlined,
                        label: l10n.chooseFromGallery,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPickerCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(
          color: context.settingCardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: context.borderTheme,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.blue,
                size: 28.w,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    context.read<SignUpProvider>().setAvatarFile(_imageFile);
    Navigator.pushNamed(
      context,
      AppRoutes.setupPassword,
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
                          SizedBox(height: 16.h),
                          Center(
                            child: GestureDetector(
                              onTap: () => _showPickerBottomSheet(context),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 15.r,
                                          spreadRadius: 2.r,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 80.r,
                                      backgroundColor: context.cardBg,
                                      backgroundImage: _imageFile != null
                                          ? FileImage(_imageFile!) as ImageProvider
                                          : const AssetImage('assets/images/avatar.jpg'),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 4.w,
                                    child: Container(
                                      height: 42.r,
                                      width: 42.r,
                                      decoration: BoxDecoration(
                                        color: AppColors.blue,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: context.scaffoldBg,
                                          width: 3.w,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 18.r,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 28.h),
                          Text(
                            l10n.avatar,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            l10n.setupAvatarDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: context.textMuted,
                            ),
                          ),
                          const Spacer(),
                          SizedBox(height: 24.h),
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
}
