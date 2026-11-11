import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';

class EditPhoneScreen extends StatefulWidget {
  final String? initialPhone;

  const EditPhoneScreen({
    super.key,
    this.initialPhone,
  });

  @override
  State<EditPhoneScreen> createState() => _EditPhoneScreenState();
}

class _EditPhoneScreenState extends State<EditPhoneScreen> {
  late final TextEditingController _phoneController;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _phoneController.addListener(() {
      setState(() {});
    });
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return;

    final phone = _phoneController.text.trim();

    if (phone.isNotEmpty) {
      final phoneRegex = RegExp(r'^[0-9+ ]{8,15}$');
      if (!phoneRegex.hasMatch(phone)) {
        AppToast.error(context, l10n.invalidPhoneNumber);
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateSingleField(
        fieldKey: 'phone',
        value: phone,
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updatePhoneSuccess);
        } else {
          AppToast.info(context, l10n.phoneSaved);
        }
        Navigator.pop(context, phone);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingPhone);
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
            l10n.phoneNumber,
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
                    child: Icon(Icons.phone_outlined, size: 36.r, color: AppColors.blue),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Text(
                    l10n.yourPhoneNumber,
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
                    l10n.phoneDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 28.h),

                Text(
                  l10n.phoneHeader,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 8.h),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
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
                    controller: _phoneController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      LengthLimitingTextInputFormatter(15),
                    ],
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                    cursorColor: AppColors.blue,
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: l10n.enterPhoneHint,
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: context.textMuted.withValues(alpha: 0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(Icons.phone_rounded, color: AppColors.blue, size: 20.r),
                      suffixIcon: _phoneController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel_rounded, color: context.textMuted, size: 18.r),
                              onPressed: () => _phoneController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
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
                            l10n.savePhone,
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
