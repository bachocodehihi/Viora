import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';

class EditIntroductionScreen extends StatefulWidget {
  final String? initialBio;

  const EditIntroductionScreen({
    super.key,
    this.initialBio,
  });

  @override
  State<EditIntroductionScreen> createState() => _EditIntroductionScreenState();
}

class _EditIntroductionScreenState extends State<EditIntroductionScreen> {
  late final TextEditingController _bioController;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;
  static const int _maxChars = 150;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.initialBio ?? '');
    _bioController.addListener(() {
      setState(() {});
    });
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return;

    final bio = _bioController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateSingleField(
        fieldKey: 'bio',
        value: bio,
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateBioSuccess);
        } else {
          AppToast.info(context, l10n.bioSaved);
        }
        Navigator.pop(context, bio);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingBio);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLength = _bioController.text.length;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20.r),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.bio,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 72.r,
                    height: 72.r,
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.format_quote_rounded, size: 36.r, color: AppColors.blue),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Text(
                    l10n.yourBio,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Center(
                  child: Text(
                    l10n.bioDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 28.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.bioHeader,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: context.textMuted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      '$currentLength/$_maxChars',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: currentLength >= _maxChars ? Colors.redAccent : context.textMuted,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? AppColors.blue
                          : context.borderTheme.withValues(alpha: 0.4),
                      width: _focusNode.hasFocus ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _bioController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_maxChars),
                    ],
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                    cursorColor: AppColors.blue,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: l10n.enterBioHint,
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: context.textMuted.withValues(alpha: 0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.saveBio,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
