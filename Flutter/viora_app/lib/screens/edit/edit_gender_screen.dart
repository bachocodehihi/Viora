import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';

class EditGenderScreen extends StatefulWidget {
  final String? initialGender;

  const EditGenderScreen({
    super.key,
    this.initialGender,
  });

  @override
  State<EditGenderScreen> createState() => _EditGenderScreenState();
}

class _EditGenderScreenState extends State<EditGenderScreen> {
  String? _selectedGender;
  bool _isSaving = false;

  List<Map<String, dynamic>> get _genderOptions => [
    {
      'key': 'male',
      'label': l10n.maleGender,
      'icon': Icons.man_rounded,
      'color': AppColors.blue,
      'desc': l10n.maleGenderDesc,
    },
    {
      'key': 'female',
      'label': l10n.femaleGender,
      'icon': Icons.woman_rounded,
      'color': AppColors.pink,
      'desc': l10n.femaleGenderDesc,
    },
    {
      'key': 'other',
      'label': l10n.otherGender,
      'icon': Icons.transgender_rounded,
      'color': AppColors.purple,
      'desc': l10n.otherGenderDesc,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialGender != null && widget.initialGender!.isNotEmpty) {
      final g = widget.initialGender!.toLowerCase().trim();
      if (g == 'male' || g == 'female' || g == 'other') {
        _selectedGender = g;
      }
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await ProfileService.updateSingleField(
        fieldKey: 'gender',
        value: _selectedGender,
      );

      if (mounted) {
        if (success) {
          AppToast.success(context, l10n.updateGenderSuccess);
        } else {
          AppToast.info(context, l10n.genderSaved);
        }
        Navigator.pop(context, _selectedGender);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.errorSavingGender);
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
    return Scaffold(
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
          l10n.gender,
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
                  child: Icon(Icons.wc_rounded, size: 36.r, color: AppColors.blue),
                ),
              ),
              SizedBox(height: 20.h),
              Center(
                child: Text(
                  l10n.chooseYourGender,
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
                  l10n.genderDesc,
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
                l10n.genderOptionsHeader,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: context.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(height: 10.h),

              ..._genderOptions.map((opt) {
                final key = opt['key'] as String;
                final label = opt['label'] as String;
                final icon = opt['icon'] as IconData;
                final color = opt['color'] as Color;
                final desc = opt['desc'] as String;
                final isSelected = _selectedGender == key;

                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedGender = key;
                      });
                    },
                    borderRadius: BorderRadius.circular(16.r),
                    child: Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.08)
                            : context.cardBg,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : context.borderTheme.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42.r,
                            height: 42.r,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 22.r),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? color : context.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? color : context.textMuted.withValues(alpha: 0.4),
                            size: 22.r,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

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
                          l10n.saveGender,
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
    );
  }
}
