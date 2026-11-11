import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/dialog/birthday_dialog.dart';
import '../../widgets/toast/app_toast.dart';

class EditBirthdayScreen extends StatefulWidget {
  final DateTime? initialBirthday;

  const EditBirthdayScreen({
    super.key,
    this.initialBirthday,
  });

  @override
  State<EditBirthdayScreen> createState() => _EditBirthdayScreenState();
}

class _EditBirthdayScreenState extends State<EditBirthdayScreen> {
  DateTime? _selectedDate;
  late final TextEditingController _birthdayController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialBirthday;
    _birthdayController = TextEditingController(
      text: _selectedDate != null ? _formatDate(_selectedDate!) : '',
    );
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')} - ${dt.month.toString().padLeft(2, '0')} - ${dt.year}';
  }

  Future<void> _selectBirthdayDialog() async {
    FocusScope.of(context).unfocus();
    final today = DateTime.now();
    final DateTime initialDate =
        _selectedDate ?? DateTime(today.year - 18, today.month, today.day);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return BirthdayDialog(
          initialDate: initialDate,
          onConfirm: (DateTime picked) {
            setState(() {
              _selectedDate = picked;
              _birthdayController.text = _formatDate(picked);
            });
          },
        );
      },
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    if (_selectedDate == null) {
      AppToast.error(context, l10n.selectBirthdayWarning);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateSingleField(
        fieldKey: 'birthday',
        value: _selectedDate!.toIso8601String(),
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateBirthdaySuccess);
        } else {
          AppToast.info(context, l10n.birthdaySaved);
        }
        Navigator.pop(context, _selectedDate);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingBirthday);
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
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: context.textPrimary, size: 20.r),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.birthday,
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
                    child: Icon(Icons.cake_outlined,
                        size: 36.r, color: AppColors.blue),
                  ),
                ),
                SizedBox(height: 20.h),
                Center(
                  child: Text(
                    l10n.yourBirthday,
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
                    l10n.selectBirthdayDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: context.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 32.h),

                Text(
                  l10n.birthdayHeader,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: context.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 10.h),

                InkWell(
                  onTap: _selectBirthdayDialog,
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: _selectedDate != null
                            ? AppColors.blue.withValues(alpha: 0.6)
                            : context.borderTheme.withValues(alpha: 0.4),
                        width: _selectedDate != null ? 1.5 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _birthdayController,
                      readOnly: true,
                      onTap: _selectBirthdayDialog,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: l10n.selectBirthdayHint,
                        hintStyle: TextStyle(
                          fontSize: 15.sp,
                          color: context.textMuted.withValues(alpha: 0.5),
                          fontWeight: FontWeight.normal,
                        ),
                        prefixIcon: Icon(
                          Icons.cake_outlined,
                          color: AppColors.blue,
                          size: 20.r,
                        ),
                        suffixIcon: Icon(
                          Icons.calendar_month_rounded,
                          color: AppColors.blue,
                          size: 20.r,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20.r,
                            height: 20.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.saveBirthday,
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
