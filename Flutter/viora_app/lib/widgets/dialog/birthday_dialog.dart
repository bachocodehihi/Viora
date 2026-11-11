import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../config/app_colors.dart';
import '../../config/theme_helper.dart';
import '../../l10n/language.dart';

class BirthdayDialog extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  const BirthdayDialog({
    super.key,
    required this.initialDate,
    required this.onConfirm,
  });

  @override
  State<BirthdayDialog> createState() => _BirthdayDialogState();
}

class _BirthdayDialogState extends State<BirthdayDialog> {
  late int day;
  late int month;
  late int year;

  late List<String> days;
  late List<String> years;

  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    day = widget.initialDate.day;
    month = widget.initialDate.month;
    year = widget.initialDate.year;

    _dayController = FixedExtentScrollController(initialItem: day - 1);
    _monthController = FixedExtentScrollController(initialItem: month - 1);
    _yearController = FixedExtentScrollController(initialItem: year - 1900);

    final int currentYear = DateTime.now().year;
    years = List.generate(currentYear - 1900 + 1, (i) => (1900 + i).toString());
    _updateDays(shouldJump: false);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateDays({bool shouldJump = true}) {
    final maxDay = DateUtils.getDaysInMonth(year, month);
    days = List.generate(maxDay, (i) => (i + 1).toString().padLeft(2, '0'));
    if (day > maxDay) {
      day = maxDay;
      if (shouldJump) {
        _dayController.jumpToItem(day - 1);
      }
    }
  }

  void _onConfirm() {
    widget.onConfirm(DateTime(year, month, day));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dialogBg = context.cardBg;

    final List<String> months = [
      l10n.jan,
      l10n.feb,
      l10n.mar,
      l10n.apr,
      l10n.may,
      l10n.jun,
      l10n.jul,
      l10n.aug,
      l10n.sep,
      l10n.oct,
      l10n.nov,
      l10n.dec,
    ];

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: kIsWeb ? 24.w : 24.w,
          vertical: 28.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.selectBirthday,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.day,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.month,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.year,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            SizedBox(
              width: double.infinity,
              height: 160.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _wheel(
                        items: days,
                        controller: _dayController,
                        onChanged: (i) => setState(() => day = i + 1),
                      ),
                      _wheel(
                        items: months,
                        controller: _monthController,
                        onChanged: (i) => setState(() {
                          month = i + 1;
                          _updateDays();
                        }),
                      ),
                      _wheel(
                        items: years,
                        controller: _yearController,
                        onChanged: (i) => setState(() {
                          year = int.parse(years[i]);
                          _updateDays();
                        }),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Column(
                      children: [
                        Container(
                          height: 55.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                dialogBg,
                                dialogBg.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 55.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                dialogBg,
                                dialogBg.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48.h),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              onPressed: _onConfirm,
              child: Text(
                l10n.continuee,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required List<String> items,
    required FixedExtentScrollController controller,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        itemExtent: 44.h,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.003,
        diameterRatio: 2.5,
        controller: controller,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (_, i) => Center(
            child: Text(
              items[i],
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
