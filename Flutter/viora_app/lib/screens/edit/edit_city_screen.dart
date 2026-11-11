import '../../l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../services/profile_service.dart';
import '../../widgets/toast/app_toast.dart';
class EditCityScreen extends StatefulWidget {
  final String? initialCity;

  const EditCityScreen({
    super.key,
    this.initialCity,
  });

  @override
  State<EditCityScreen> createState() => _EditCityScreenState();
}

class _EditCityScreenState extends State<EditCityScreen> {
  late final TextEditingController _cityController;
  final FocusNode _focusNode = FocusNode();
  bool _isSaving = false;

  List<String> get _popularCities => l10n.popularCitiesList;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialCity ?? '');
    _cityController.addListener(() => setState(() {}));
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cityController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return;
    final city = _cityController.text.trim();
    setState(() => _isSaving = true);
    try {
      await ProfileService.updateSingleField(fieldKey: 'city', value: city);
      if (mounted) {
        AppToast.success(context, l10n.updateCitySuccess);
        Navigator.pop(context, city);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context, city);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            l10n.provinceCity,
            style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 20.sp),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    controller: _cityController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: context.textPrimary),
                    cursorColor: AppColors.blue,
                    decoration: InputDecoration(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintText: l10n.enterCityHint,
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: context.textMuted.withValues(alpha: 0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(Icons.location_city_rounded, color: AppColors.blue, size: 20.r),
                      suffixIcon: _cityController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel_rounded, color: context.textMuted, size: 18.r),
                              onPressed: () => _cityController.clear(),
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
                SizedBox(height: 20.h),
                Text(
                  l10n.popularCities,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: context.textMuted, letterSpacing: 1.1),
                ),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _popularCities.map((city) {
                    return ActionChip(
                      label: Text(city),
                      backgroundColor: context.cardBg,
                      onPressed: () => setState(() => _cityController.text = city),
                    );
                  }).toList(),
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
                            l10n.saveCity,
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
