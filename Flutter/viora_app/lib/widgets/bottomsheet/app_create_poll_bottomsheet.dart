import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';
import '../toast/app_toast.dart';

class AppCreatePollBottomSheet extends StatefulWidget {
  const AppCreatePollBottomSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AppCreatePollBottomSheet(),
    );
  }

  @override
  State<AppCreatePollBottomSheet> createState() => _AppCreatePollBottomSheetState();
}

class _AppCreatePollBottomSheetState extends State<AppCreatePollBottomSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multipleAnswers = false;

  @override
  void initState() {
    super.initState();
    _questionController.addListener(_onTextChanged);
    for (var c in _optionControllers) {
      c.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (var c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    final controller = TextEditingController();
    controller.addListener(_onTextChanged);
    setState(() {
      _optionControllers.add(controller);
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      final removed = _optionControllers.removeAt(index);
      removed.dispose();
    });
  }

  bool get _canSubmit {
    final question = _questionController.text.trim();
    if (question.isEmpty) return false;
    final validOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return validOptions.length >= 2;
  }

  void _submit() {
    final l10n = context.l10n;
    final question = _questionController.text.trim();
    final validOptions = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (question.isEmpty || validOptions.length < 2) {
      AppToast.show(context, l10n.pollMinRequirement, isError: true);
      return;
    }

    Navigator.pop(context, {
      'question': question,
      'options': validOptions.asMap().entries.map((e) => {
        'id': '${e.key + 1}',
        'text': e.value,
      }).toList(),
      'multipleAnswers': _multipleAnswers,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: context.dividerTheme,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.poll_rounded, color: AppColors.blue, size: 20.r),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      l10n.createPoll,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.textMuted, size: 22.r),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.dividerTheme),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      l10n.pollQuestion,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _questionController,
                      maxLines: 2,
                      minLines: 1,
                      style: TextStyle(fontSize: 14.sp, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: l10n.pollQuestionHint,
                        hintStyle: TextStyle(fontSize: 13.5.sp, color: context.textMuted),
                        filled: true,
                        fillColor: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.08),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: context.dividerTheme),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(color: context.dividerTheme),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.pollOptions,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          '${l10n.pollOptionHint} 1 & 2 (*)',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),

                    ...List.generate(_optionControllers.length, (index) {
                      final controller = _optionControllers[index];
                      final isRemovable = _optionControllers.length > 2;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          children: [
                            Container(
                              width: 24.r,
                              height: 24.r,
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.blue,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                style: TextStyle(fontSize: 13.5.sp, color: context.textPrimary),
                                decoration: InputDecoration(
                                  hintText: '${l10n.pollOptionHint} ${index + 1}...',
                                  hintStyle: TextStyle(fontSize: 13.sp, color: context.textMuted),
                                  filled: true,
                                  fillColor: context.isDark ? const Color(0xFF1E1E2C) : Colors.grey.withValues(alpha: 0.08),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: BorderSide(color: context.dividerTheme),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: BorderSide(color: context.dividerTheme),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                            if (isRemovable) ...[
                              SizedBox(width: 6.w),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20.r),
                                onPressed: () => _removeOption(index),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    if (_optionControllers.length < 10) ...[
                      SizedBox(height: 4.h),
                      InkWell(
                        onTap: _addOption,
                        borderRadius: BorderRadius.circular(10.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.blue.withValues(alpha: 0.5), width: 1),
                            borderRadius: BorderRadius.circular(10.r),
                            color: AppColors.blue.withValues(alpha: 0.05),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, color: AppColors.blue, size: 18.r),
                              SizedBox(width: 6.w),
                              Text(
                                l10n.pollAddOption,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 18.h),
                    Divider(height: 1, color: context.dividerTheme),
                    SizedBox(height: 8.h),

                    Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: AppColors.blue, size: 20.r),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            l10n.pollMultipleAnswers,
                            style: TextStyle(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _multipleAnswers,
                          activeTrackColor: AppColors.blue,
                          onChanged: (val) => setState(() => _multipleAnswers = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    disabledBackgroundColor: AppColors.blue.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    l10n.createPoll,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

